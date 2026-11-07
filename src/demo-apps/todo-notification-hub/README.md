# todo-notification-hub

Minimal Node.js (Express 5) service that receives a notification from [todo-front](../todo-front) every time a todo is created.
For now it only **logs the payload**: the same JSON body todo-front sends to [todo-store](../todo-store), e.g. `{"title":"..."}`.

## Endpoints
| Method & path | Description |
|---|---|
| `POST /api/notifications` | Logs the payload → `202` |
| `GET /healthz` | health probe |

todo-front calls it after todo-store answered `201`, using `TODO_NOTIFICATION_HUB_URL` (default `http://todo-notification-hub`).
If the hub is down todo-front only logs a warning; the todo is still created.

## Run locally
```bash
npm install
npm run dev               # listens on http://localhost:3000, restarts on file changes
curl -X POST localhost:3000/api/notifications -H 'Content-Type: application/json' -d '{"title":"hello"}'
```

## Build the image
```bash
docker build -t todo-notification-hub:latest .
```

## Run locally with todo-front and todo-store
```bash
docker network create todo
docker run -d --rm --name todo-store --network todo todo-store:latest
docker run -d --rm --name todo-notification-hub --network todo todo-notification-hub:latest
docker run -d --rm --name todo-front --network todo -p 7123:7123 \
  -e TODO_STORE_URL=http://todo-store:8080 -e TODO_NOTIFICATION_HUB_URL=http://todo-notification-hub:3000 todo-front:latest
curl -X POST localhost:7123/api/todos -H 'Content-Type: application/json' -d '{"title":"hello"}'
docker logs todo-notification-hub   # todo created: {"title":"hello"}
# cleanup
docker stop todo-front todo-notification-hub todo-store && docker network rm todo
```

## Push to the registry
`k8s/deployment.yaml` pulls `reg.k.codersandbox.com/todo-notification-hub:latest`:
```bash
docker tag todo-notification-hub:latest reg.k.codersandbox.com/todo-notification-hub:latest
docker push reg.k.codersandbox.com/todo-notification-hub:latest
curl https://reg.k.codersandbox.com/v2/todo-notification-hub/tags/list
```
Or run `../build-push.sh && ../deploy.sh` to build, push and redeploy all services.

## Deploy to Kubernetes
```bash
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/deployment.yaml
kubectl -n apps rollout status deploy/todo-notification-hub
kubectl -n apps logs -f deploy/todo-notification-hub
```

## Cleanup
```bash
kubectl delete -f k8s/deployment.yaml
```
