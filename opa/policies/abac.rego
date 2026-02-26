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

allow if {
  input.action == "read"
  input.resource == "orders"
  not high_risk
}

allow if {
  input.action == "admin"
  roles_contains("admin")
  not high_risk
}

high_risk if {
  input.score >= 70
}

roles_contains(r) if {
  some i
  input.roles[i] == r
}
