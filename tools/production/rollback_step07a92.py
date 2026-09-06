from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[2]
FILES=[ROOT/'lib/main.dart',ROOT/'lib/screens/welcome_page.dart']
n=0
for p in FILES:
    b=p.with_suffix(p.suffix+'.step07a92.bak')
    if b.exists(): shutil.copy2(b,p); print('[RESTORED]',p.relative_to(ROOT)); n+=1
print('[INFO] Restored:',n,'/',len(FILES))
if n!=len(FILES): raise SystemExit('[FAIL] rollback incomplete')
