# todo-store

Minimal Spring Boot 4.1.1 REST service on **Java 25** (LTS) that stores todos for [todo-front](../todo-front).
Todos are kept **in memory only**: they are lost on restart, and each replica has its own list (the Deployment runs 1 replica).

## Endpoints
| Method & path | Description |
|---|---|
| `GET /api/todos` | List todos (ordered by id) |
| `GET /api/todos/{id}` | Get one todo (`404` if missing) |
| `POST /api/todos` | Create: `{"title": "..."}` → `201` with `{"id":1,"title":"...","done":false}` |
| `PUT /api/todos/{id}` | Update: `{"title": "...", "done": true}` (both optional) |
| `DELETE /api/todos/{id}` | Delete → `204` (`404` if missing) |
| `GET /healthz` | health probe |

## Run locally
```bash
mvn spring-boot:run        # listens on http://localhost:8080
curl -X POST localhost:8080/api/todos -H 'Content-Type: application/json' -d '{"title":"hello"}'
curl localhost:8080/api/todos
```

## Build the image
```bash
docker build -t todo-store:latest .
```

## Run locally with todo-front
```bash
docker network create todo
docker run -d --rm --name todo-store --network todo todo-store:latest
docker run -d --rm --name todo-front --network todo -p 7123:7123 -e TODO_STORE_URL=http://todo-store:8080 todo-front:latest
open http://localhost:7123/
# cleanup
docker stop todo-front todo-store && docker network rm todo
```

## Push to the registry
`k8s/deployment.yaml` pulls `reg.k.codersandbox.com/todo-store:latest`:
```bash
docker tag todo-store:latest reg.k.codersandbox.com/todo-store:latest
docker push reg.k.codersandbox.com/todo-store:latest
curl https://reg.k.codersandbox.com/v2/todo-store/tags/list
```
Or run `../build-push.sh && ../deploy.sh` to build, push and redeploy both services.

## Deploy to Kubernetes
```bash
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/deployment.yaml
kubectl -n apps rollout status deploy/todo-store
kubectl -n apps port-forward svc/todo-store 8080:80
```
The pod is annotated for OpenTelemetry Operator Java auto-instrumentation (`otel-instrumentation` CR in `opentelemetry-kube-stack-values.yml`).

## Cleanup
```bash
kubectl delete -f k8s/deployment.yaml
```
