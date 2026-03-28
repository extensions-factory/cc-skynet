<!-- @hook:SessionStart -->
The SessionStart hooks above each end with a status line: `<name> loaded`, `<name> run`, or `<name> failed`.

In your first response, greet and show a 2-line summary of hook statuses.

``` Template

[<AGENT_NAME>] Online, sẵn sàng phục vụ
  X rules loaded, Y commands run

```

``` Example

[SKYNET] Online, sẵn sàng phục vụ
  3 rules loaded, 2 commands run

```

If any hook failed, add a third line listing the failures:
```
  ⚠ <name> failed
```

Then continue with the user's request.
<!-- @end:SessionStart -->
