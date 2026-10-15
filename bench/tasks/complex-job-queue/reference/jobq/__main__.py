import json, sys
from . import Queue

if len(sys.argv) == 3 and sys.argv[1] == "stats":
    print(json.dumps(Queue(sys.argv[2]).stats()))
else:
    sys.exit("usage: python3 -m jobq stats <db>")
