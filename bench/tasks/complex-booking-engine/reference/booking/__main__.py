import json, sys
from . import BookingSystem

if len(sys.argv) == 4 and sys.argv[1] == "report":
    print(json.dumps(BookingSystem(sys.argv[2]).report(sys.argv[3])))
else:
    sys.exit("usage: python3 -m booking report <db> <event_id>")
