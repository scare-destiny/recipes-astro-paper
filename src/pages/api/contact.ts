export const prerender = false;
import type { APIRoute } from "astro";

export const POST: APIRoute = async ({ request }) => {
  const data = await request.json().catch(() => ({}));
  const { name, email, message } = data as {
    name?: string;
    email?: string;
    message?: string;
  };

  if (!name || !email || !message) {
    return new Response(
      JSON.stringify({ message: "Missing required fields" }),
      { status: 400 }
    );
  }

  try {
    const response = await fetch(
      "https://n8n.venger.me/webhook/8cc624fd-96f3-4bef-8d0e-cd9759503a66",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ name, email, message }),
      }
    );

    // 1. Capture the actual error
    if (!response.ok) {
      const errorText = await response.text();
      // 2. Log it to your server console so you can read it in your terminal/logs
      console.error(
        `[Contact Form]  webhook failed: ${response.status} ${response.statusText}`
      );
      console.error(`[Contact Form] response body:`, errorText);

      throw new Error(
        `Webhook rejected the request (Status: ${response.status})`
      );
    }

    return new Response(JSON.stringify({ message: "Success!" }), {
      status: 200,
    });
  } catch (error) {
    // 3. Catch and log network errors (e.g., DNS issues, timeouts)
    console.error("[Contact Form] Server caught an error:", error);

    return new Response(
      JSON.stringify({
        message: "Failed to send message. Please try again later.",
        // 4. Optionally pass the technical error string back for debugging in the browser console
        debug: error instanceof Error ? error.message : String(error),
      }),
      { status: 500 }
    );
  }
};
