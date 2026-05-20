import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from './cors.ts';

/** Return a JSON Response with CORS headers. */
export function jsonResponse(
  data: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/** Shortcut for error responses. */
export function errorResponse(
  message: string,
  status: number,
  code?: string,
): Response {
  return jsonResponse(
    { error: message, ...(code ? { code } : {}) },
    status,
  );
}

/**
 * Authenticate the request and return the user.
 * Returns the user object or an error Response.
 */
export async function requireAuth(
  supabase: SupabaseClient,
): Promise<
  | { user: { id: string; email?: string }; error?: never }
  | { user?: never; error: Response }
> {
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return { error: errorResponse('Unauthorized', 401) };
  }
  return { user };
}

/** Validate that required string fields are present in the body. */
export function assertFields(
  body: Record<string, unknown>,
  fields: string[],
): string | null {
  for (const field of fields) {
    if (body[field] === undefined || body[field] === null || body[field] === '') {
      return `${field} is required`;
    }
  }
  return null;
}
