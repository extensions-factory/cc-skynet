<!-- @hook:SessionStart -->
The SessionStart hooks above each end with a status line: `<name> hooked` or `<name> failed to hook`.

In your first response, greet and show those statuses so the user sees what loaded.

``` Template

[<AGENT_NAME>] Online, sẵn sàng phục vụ
  List hooks statuses here, one per line, indented by two spaces, in the format:
  <hook_name> <status>

```

``` Example:

[SKYNET] Online, sẵn sàng phục vụ
  user-priority hooked
  setup hooked
  source-sync hooked
  auto-discover hooked
```

Then continue with the user's request.
<!-- @end:SessionStart -->
