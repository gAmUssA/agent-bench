import json, urllib.request, sys, statistics
PROMPT = "Write a Python function that merges overlapping intervals in a list of (start, end) tuples, with a docstring and three assert-based tests. Output only code."
def post(url, body):
    r = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(r, timeout=900))
def llama(port):
    d = post("http://127.0.0.1:%s/v1/chat/completions" % port, {"messages": [{"role": "user", "content": PROMPT}], "max_tokens": 400, "temperature": 0, "chat_template_kwargs": {"reasoning_effort": "low"}})
    t = d["timings"]; return t["predicted_per_second"], d["usage"]["completion_tokens"], "%s/%s" % (t.get("draft_n_accepted"), t.get("draft_n"))
def ollama(model):
    d = post("http://127.0.0.1:11434/api/chat", {"model": model, "stream": False, "messages": [{"role": "user", "content": PROMPT}], "options": {"temperature": 0, "num_predict": 400}})
    return d["eval_count"]/d["eval_duration"]*1e9, d["eval_count"], "-"
kind, arg, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
fn = (lambda: llama(arg)) if kind == "llama" else (lambda: ollama(arg))
fn()  # warmup, discarded
v = []
for i in range(n):
    r = fn(); v.append(r[0]); print("run %d decode %.1f t/s tokens %d draft %s" % (i, *r), flush=True)
print("SUMMARY %s %s min %.1f median %.1f max %.1f" % (kind, arg, min(v), statistics.median(v), max(v)))
