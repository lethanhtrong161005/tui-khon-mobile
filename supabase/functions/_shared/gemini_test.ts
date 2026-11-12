import { generateJson } from "./gemini.ts";
import { HttpError } from "./http.ts";
const options = {
  system: "test",
  contents: [{ role: "user" as const, parts: [{ text: "test" }] }],
  schema: { type: "OBJECT" },
};
const response = (text: string) =>
  new Response(
    JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }),
  );
function assert(value: unknown, message = "assertion failed") {
  if (!value) throw new Error(message);
}
Deno.test("transient provider error retries once, preserving payload and API key header", async () => {
  const bodies: unknown[] = [];
  const result = await generateJson<{ ok: boolean }>(options, {
    apiKey: "test-key",
    delay: async () => {},
    fetch: ((_url, init) => {
      bodies.push(init?.body);
      assert(
        (init?.headers as Record<string, string>)["x-goog-api-key"] ===
          "test-key",
      );
      return Promise.resolve(
        bodies.length === 1
          ? new Response("private upstream content", { status: 503 })
          : response('{"ok":true}'),
      );
    }) as typeof fetch,
  });
  assert(result.ok && bodies.length === 2 && bodies[0] === bodies[1]);
});
Deno.test("busy retry stops after two calls and exposes no upstream body", async () => {
  let count = 0;
  try {
    await generateJson(options, {
      apiKey: "test",
      delay: async () => {},
      fetch: (() => {
        count++;
        return Promise.resolve(
          new Response("private upstream content", { status: 503 }),
        );
      }) as typeof fetch,
    });
    throw new Error("expected failure");
  } catch (e) {
    assert(e instanceof HttpError && e.code === "AI_BUSY");
    assert(!String(e).includes("private"));
  }
  assert(count === 2);
});
Deno.test("non-transient failures and invalid JSON are not retried", async () => {
  for (
    const res of [
      new Response("secret", { status: 400 }),
    new Response("not JSON"),
      response("not JSON"),
      response("[]"),
    ]
  ) {
    let count = 0;
    try {
      await generateJson(options, {
        apiKey: "test",
        delay: async () => {},
        fetch: (() => {
          count++;
          return Promise.resolve(res);
        }) as typeof fetch,
      });
      throw new Error("expected failure");
    } catch (e) {
      assert(e instanceof HttpError);
    }
    assert(count === 1);
  }
});
