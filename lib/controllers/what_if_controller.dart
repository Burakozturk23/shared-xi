import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/what_if.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/journey_gateway.dart';
import '../services/what_if_store.dart';

class WhatIfController extends ChangeNotifier {
  WhatIfController({required this.catalog, WhatIfStore? store, JourneyGateway? gateway,
    String? userId, Random? random}) : uid=userId ?? (AuthService.isGoogleAccount ? AuthService.uid : null),
    injected=gateway!=null, gateway=gateway ?? FirebaseJourneyGateway(whatIf:true),
    random=random ?? Random() {
      this.store=store ?? LocalWhatIfStore(uid);
    }
  final WhatIfCatalog catalog;
  final String? uid;
  final bool injected;
  final JourneyGateway gateway;
  final Random random;
  late final WhatIfStore store;
  Map<String,dynamic> local={}, cloud={};
  bool loading=true, busy=false, syncing=false, _disposed=false;
  String? error, message, feedback;
  bool get linked=>uid!=null && (injected || (AuthService.isGoogleAccount && AuthService.uid==uid));
  bool get accountValid=>injected || (AuthService.isGoogleAccount ? AuthService.uid : null)==uid;
  bool get pro=>cloud['pro']==true;
  void _notify(){if(!_disposed) notifyListeners();}
  @override
  void dispose(){_disposed=true;super.dispose();}
  Future<void> initialize() async {
    loading=true;error=null;_notify();
    try {
      final value=await store.read();
      if(value.isNotEmpty && (value['version']!=1 || value['progress'] is! Map || value['proofs'] is! Map)) {
        throw const FormatException('Invalid What If save');
      }
      // Malformed saves are surfaced, never silently overwritten.
      for(final entry in rewardMap(value['progress']).entries) {
        final s=catalog.scenarios.where((s)=>s.id==entry.key).firstOrNull;
        final p=rewardMap(entry.value);
        if(s==null || !{'intro','choice','task','result'}.contains(p['phase']) ||
            (p['route']!=null && !s.routes.any((r)=>r.id==p['route']))) throw const FormatException('Invalid checkpoint');
        if(p['route']!=null) {
          final t=s.route(p['route'] as String).task;
          final order=List<String>.from(p['order'] as List? ?? []);
          final picked=List<String>.from(p['picked'] as List? ?? []);
          if(order.length!=t.options.length || order.toSet().length!=order.length ||
              !order.every(t.options.containsKey) || !picked.every(t.options.containsKey)) {
            throw const FormatException('Invalid task checkpoint');
          }
        }
      }
      local=value.isEmpty ? {'version':1,'progress':<String,dynamic>{},'proofs':<String,dynamic>{},'favorites':<String>[]} : value;
    } catch (_) {error='Kayıt okunamadı. İlerlemeni silmedik; yeniden yüklemeyi dene.';}
    loading=false;_notify();
    // The UI calls sync separately; offline play never waits for the server.
  }
  Map<String,dynamic> progress(WhatIfScenario s)=>rewardMap(rewardMap(local['progress'])[s.id]);
  String phase(WhatIfScenario s)=>progress(s)['phase']?.toString() ?? 'intro';
  WhatIfRoute? route(WhatIfScenario s)=>progress(s)['route']==null ? null : s.route(progress(s)['route'] as String);
  List<String> order(WhatIfScenario s)=>List<String>.from(progress(s)['order'] as List? ?? []);
  List<String> picked(WhatIfScenario s)=>List<String>.from(progress(s)['picked'] as List? ?? []);
  Set<String> ends(WhatIfScenario s)=>{
    ...List<String>.from(progress(s)['ends'] as List? ?? []),
    ...rewardMap(rewardMap(rewardMap(cloud['progress'])[s.id])['ends']).keys,
  };
  int get complete=>catalog.scenarios.where((s)=>ends(s).isNotEmpty).length;
  int get dual=>catalog.scenarios.where((s)=>ends(s).length==2).length;
  Set<String> get favorites=>List<String>.from(local['favorites'] as List? ?? []).toSet();
  Set<String> get showcase=>List<String>.from(cloud['favorites'] as List? ?? []).toSet();
  Map<String,dynamic> get rewards=>rewardMap(cloud['rewards']);
  bool hintUnlocked(WhatIfScenario s) {
    final t=route(s)?.task;if(t==null)return false;
    final h=rewardMap(rewardMap(cloud['hints'])[t.id]);return h['coin']==true||h['ad']==true;
  }
  Future<bool> _edit(void Function(Map<String,dynamic>) fn) async {
    if(busy || loading || error!=null || !accountValid)return false;
    busy=true;message=null;_notify();
    try {
      final next=jsonDecode(jsonEncode(local)) as Map<String,dynamic>;
      fn(next);await store.write(next);
      local=next;return true;
    } catch (_) {message='Kaydedilemedi. Aynı adımdasın; yeniden dene.';return false;}
    finally {busy=false;_notify();}
  }
  Map<String,dynamic> _p(Map<String,dynamic> l,WhatIfScenario s)=>
    (l['progress'] as Map<String,dynamic>).putIfAbsent(s.id,()=> <String,dynamic>{'phase':'intro','ends':<String>[]}) as Map<String,dynamic>;
  Future<void> setPhase(WhatIfScenario s,String phase) async {
    feedback=null;await _edit((l)=>_p(l,s)['phase']=phase);
  }
  Future<void> selectRoute(WhatIfScenario s,String id) async {
    feedback=null;
    await _edit((l){final p=_p(l,s),t=s.route(id).task;
      p['route']=id;p['phase']='task';p['order']=t.shuffled(random);p['picked']=<String>[];
      p['freeHints']??=<String>[];
    });
  }
  Future<void> choose(WhatIfScenario s,String key) async {
    final r=route(s);if(r==null || !r.task.options.containsKey(key))return;
    feedback=null;
    await _edit((l){final p=_p(l,s);final selected=List<String>.from(p['picked'] as List? ?? []);
      if(r.task.timeline){selected.contains(key)?selected.remove(key):selected.add(key);p['picked']=selected;}
      else{p['picked']=[key];}
    });
  }
  Future<void> freeHint(WhatIfScenario s) async {
    final r=route(s);if(r==null)return;
    await _edit((l){final p=_p(l,s);final hints=List<String>.from(p['freeHints'] as List? ?? []); if(!hints.contains(r.id)) hints.add(r.id); p['freeHints']=hints;});
  }
  bool freeHintShown(WhatIfScenario s)=> (progress(s)['freeHints'] as List? ?? []).contains(route(s)?.id);
  Future<void> submit(WhatIfScenario s) async {
    final r=route(s);if(r==null)return;
    final answers=picked(s);
    if(!r.task.accepts(answers)){feedback='Henüz olmadı. İpucuna bakıp yeniden deneyebilirsin.';_notify();return;}
    final ok=await _edit((l){final p=_p(l,s);
      p['ends']={...List<String>.from(p['ends'] as List? ?? []),r.id}.toList();
      p['phase']='result';
      if(linked)(l['proofs'] as Map)[r.task.id]={'version':catalog.version,'scenarioId':s.id,'routeId':r.id,'answers':answers};
    });
    if(ok){feedback=null;_notify();}
  }
  Future<void> readEnding(WhatIfScenario s,String id) async {
    if(!ends(s).contains(id))return;
    await _edit((l){final p=_p(l,s);p['route']=id;p['phase']='result';
      p['order']=s.route(id).task.shuffled(random);p['picked']=<String>[];
    });
  }
  Future<void> favorite(WhatIfScenario s) async {
    await _edit((l){final f=List<String>.from(l['favorites'] as List? ?? []);
      f.contains(s.id)?f.remove(s.id):f.add(s.id);l['favorites']=f;
    });
  }
  Future<void> sync() async {
    if(syncing || _disposed || loading || error!=null)return;
    if(!linked){message='Misafir oyunu cihazda saklanır. Coin, XP ve profil vitrini için Google hesabıyla bu rotaları oyna.';_notify();return;}
    syncing=true;message=null;_notify();
    try {
      final proofs=rewardMap(local['proofs']);
      for(final entry in proofs.entries){
        if(!linked)throw StateError('Hesap değişti');
        await gateway.call('submit',rewardMap(entry.value));
        if(!linked)throw StateError('Hesap değişti');
        // Keep bounded proofs (48 at most) for retry. Server receipts are authoritative.
      }
      final result=await gateway.call('status');
      if(!linked)throw StateError('Hesap değişti');
      cloud=result;
      // Only acknowledged evidence is removed. A concurrent newly solved route survives.
      await _edit((l){for(final s in catalog.scenarios){final seen=ends(s);if(seen.isNotEmpty)_p(l,s)['ends']=seen.toList();} final pending=l['proofs'] as Map;for(final e in proofs.entries){
        if(jsonEncode(pending[e.key])==jsonEncode(e.value))pending.remove(e.key);
      }});
    }catch(_){message='Buluta ulaşılamadı. Oynamaya devam edebilirsin; ödüller için yeniden eşitle.';}
    finally{syncing=false;_notify();}
  }
  Future<void> action(String action,Map<String,dynamic> input,{bool ad=false}) async {
    if(!linked || syncing){if(!linked)await sync();return;}
    syncing=true;message=null;_notify();
    try {
      if(ad){await gateway.watch(action,context:input);}else{await gateway.call(action,input);}
      final result=await gateway.call('status');
      if(!linked)throw StateError('Hesap değişti');cloud=result;
    }catch(e){message=e is StateError?e.message.toString():'İşlem tamamlanamadı. Bağlantını veya bakiyeni kontrol edip yeniden dene.';}
    finally{syncing=false;_notify();}
  }
}
