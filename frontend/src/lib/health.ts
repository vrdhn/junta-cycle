/**
 * Backend health check utility.
 * Calls Supabase /auth/v1/health using the publishable API key.
 */
export async function checkBackendHealth(
  supabaseUrl: string,
  apiKey: string
): Promise<boolean> {
  if (!supabaseUrl || !apiKey) {
    return false;
  }

  try {
    const cleanUrl = supabaseUrl.replace(/\/+$/, "");
    const response = await fetch(`${cleanUrl}/auth/v1/health`, {
      method: "GET",
      headers: {
        apikey: apiKey,
      },
    });
    return response.ok;
  } catch {
    return false;
  }
}
