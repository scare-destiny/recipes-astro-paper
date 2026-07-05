export const prerender = false;
import type { APIRoute } from "astro";

export const POST: APIRoute = async ({ request }) => {
  const data = await request.formData();
  const name = data.get("name");
  const email = data.get("email");
  const message = data.get("message");
  // Validate the data - you'll probably want to do more than this
  if (!name || !email || !message) {
    return new Response(
      JSON.stringify({
        message: "Missing required fields",
      }),
      { status: 400 }
    );
  }
  // Send the data to another location
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

    if (!response.ok) {
      throw new Error("Failed to send message");
    }

    // Return a success response
    return new Response(
      JSON.stringify({
        message: "Success!",
      }),
      { status: 200 }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        message: `An error ${error} occurred while sending the message.`,
      }),
      { status: 500 }
    );
  }
};
