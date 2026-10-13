# Logging

Correct logging is crucial to troubleshoot the application and understand the application flow. 
Basic constituent of a log entry are:
- fixed text
- timestamp

Log entry must be added only when something meaningful happens. 
For example in the simple workflow of our application, the app logs the following events: `url stored`, `url already stored`, `license expired` and `url storage failed`.

*A well-formatted log line has a **fixed message** (the event name) and its details as **separate fields***:

```python
logger.info("url stored", 
            extra={"url.id": url_id, 
                   "url.domain": domain, 
                   "license.remaining": 7}
            )
```

The details are kept out of the message on purpose:

- A fixed message can be counted and grouped. With `f"stored {url}"`, every line would be different.
- Each `extra` key becomes a field you can filter on (`url.domain` becomes `url_domain` in Loki).
- `trace_id`, timestamp, service and pod are **not** added by the code: the agent attaches them automatically.
- Database activity is **not** logged either. The `psycopg` instrumentation already records every SQL query, execution time and propagate the `trace_id` from the business logic. 
- Logs carry business facts the instrumentation can't know, such as `license.remaining`.

> **IMPORTANT**: to be efficient data labels must be consistent across the logs. The URL id labeled as `url.id` sometime and `url.pk` somewhere else will only create problems!

The OpenTelemetry agent also attaches **structured metadata** to each line.
The most important fields are `trace_id` and `span_id`: the ID of the request that produced the line.
