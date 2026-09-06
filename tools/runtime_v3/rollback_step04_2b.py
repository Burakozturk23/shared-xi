from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
chain = ROOT / "lib/controllers/chain_controller.dart"
bak = chain.with_suffix(chain.suffix + ".step04_2b.bak")

if bak.exists():
    shutil.copy2(bak, chain)
    print("[RESTORED] lib/controllers/chain_controller.dart")
else:
    print("[SKIP] Chain backup bulunamadi.")

print(
    "hybrid_chain_graph_service.dart kalabilir; "
    "controller rollback sonrasinda kullanilmaz."
)
