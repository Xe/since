import asyncdispatch, strutils, uri

proc parse*(s: string): tuple[host, password: string, port: Port] =
  let u = s.parseUri
  assert u.scheme == "redis"
  result = (u.hostname, u.password, u.port.parseInt.Port)

when isMainModule:
  import unittest

  suite "parsing redis uri":
    test "happy path without username/password":
      discard parse "redis://127.0.0.1:6798"
    test "happy path with username/password":
      discard parse "redis://azurediamond:hunter2@127.0.0.01:6798"
    test "non-redis scheme":
      expect(AssertionError):
        discard parse "http://yolo-swag.com"
