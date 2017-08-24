from cm_api.api_client import ApiResource

CM_HOST="127.0.0.1"
ADMIN_USER="admin"
ADMIN_PASS="Dccs12345."

API = ApiResource(CM_HOST, version=5, username=ADMIN_USER, password=ADMIN_PASS)
MANAGER = API.get_cloudera_manager()
mgmt = MANAGER.get_service()

print "restart mgmt..."
mgmt.restart().wait()

print "TIP cluster..."
tip = API.get_cluster("TIP")
tip.restart().wait()


