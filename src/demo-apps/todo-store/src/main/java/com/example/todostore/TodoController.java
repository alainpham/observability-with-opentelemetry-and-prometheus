package com.example.todostore;

import java.util.Collection;
import java.util.Map;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

// Todos are kept in memory only: they are lost when the pod restarts.
@RestController
public class TodoController {

    record CreateTodo(String title) {
    }

    // Both fields optional; null means "leave unchanged"
    record UpdateTodo(String title, Boolean done) {
    }

    private final Map<Integer, Todo> todos = new ConcurrentSkipListMap<>();
    private final AtomicInteger nextId = new AtomicInteger(1);

    @GetMapping("/api/todos")
    public Collection<Todo> list() {
        return todos.values();
    }

    @GetMapping("/api/todos/{id}")
    public ResponseEntity<Todo> get(@PathVariable int id) {
        return ResponseEntity.ofNullable(todos.get(id));
    }

    @PostMapping("/api/todos")
    public ResponseEntity<Todo> create(@RequestBody CreateTodo body) {
        if (body.title() == null || body.title().isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        var todo = new Todo(nextId.getAndIncrement(), body.title().trim(), false);
        todos.put(todo.id(), todo);
        return ResponseEntity.status(HttpStatus.CREATED).body(todo);
    }

    @PutMapping("/api/todos/{id}")
    public ResponseEntity<Todo> update(@PathVariable int id, @RequestBody UpdateTodo body) {
        if (body.title() != null && body.title().isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        var updated = todos.computeIfPresent(id, (key, todo) -> new Todo(
                id,
                body.title() != null ? body.title().trim() : todo.title(),
                body.done() != null ? body.done() : todo.done()));
        return ResponseEntity.ofNullable(updated);
    }

    @DeleteMapping("/api/todos/{id}")
    public ResponseEntity<Void> delete(@PathVariable int id) {
        return todos.remove(id) != null
                ? ResponseEntity.noContent().build()
                : ResponseEntity.notFound().build();
    }

    // Liveness / readiness probes for Kubernetes
    @GetMapping("/healthz")
    public String healthz() {
        return "healthy";
    }
}
