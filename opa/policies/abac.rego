package authz

default allow = false

# Input example:
# input = {
#   "sub": "user-123",
#   "roles": ["user"],
#   "resource": "orders",
#   "action": "read",
#   "env": {"ip": "1.2.3.4", "geo": "CN"},
#   "score": 35
# }

allow {
  input.action == "read"
  input.resource == "orders"
  not high_risk
}

allow {
  input.action == "admin"
  roles_contains("admin")
  not high_risk
}

high_risk {
  input.score >= 70
}

roles_contains(r) {
  some i
  input.roles[i] == r
}
