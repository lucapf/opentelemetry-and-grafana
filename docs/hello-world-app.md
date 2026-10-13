# The hello world app

The hello word app is a minimal application for storing urls.

The app expose a single api to store the urls 
`POST /urls?url=openapi.io `

The system allow only a fixed number of URLS to be stored and 

Store it into a table and reply:
|status code| message               |
|-----------|-----------------------|
| 200       | created/already exists|
| 403       | license expired       |
| 500       | Database not available|

## OpenTelemetry integration

The application code does not contain any telemetry setup: the OpenTelemetry operator injects the Python agent, which traces the FastAPI requests, propagate to the database calls and exports the logs.

By default the operator doesn't trace internal function calls. 
Usually business steps are traced. Is still possible to add custom traces via annotation as shown in `validate_license`.

## How the application is instrumented

The startup script runs the generic instrumentation (opentelemetry-instrument) command:

```
CMD ["/bin/bash", "-c", "opentelemetry-instrument fastapi run /hello-world/app/main.py"]
```

While the new Kubernetes kind `Instrumentation` manages the instrumentation configuration.



## Application files:
- `main.py` :  http endpoint
- `license.py`: license check
- `storage.py`: storage (PostgreSQL) access

## API

- `POST /urls` receives `{"url": "..."}`, validates it, stores it in PostgreSQL and replies
  `200 {"message": "your request has been stored!", "id": N}`.

## License

 Te application can only store 10 new URLS because the licensing model. 
If no more licenses are available the system respond with 
  `403 license expired`.
The counter is reset after each reboot

## Logging

The logging convention (fixed event message, details in `extra={...}`).
See the [logging doc](./logging.md) for further detail.


