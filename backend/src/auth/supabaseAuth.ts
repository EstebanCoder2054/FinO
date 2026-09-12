import { ApiError } from "../api/errors.js";

export type SupabaseAuthClient = {
  auth: {
    getUser: (token: string) => Promise<{
      data: {
        user: {
          id: string;
        } | null;
      };
      error: unknown;
    }>;
  };
};

export async function getAuthenticatedUserId(
  token: string,
  client: SupabaseAuthClient
): Promise<string> {
  const { data, error } = await client.auth.getUser(token);

  if (error || !data.user?.id) {
    throw new ApiError(401, "unauthorized", "Invalid authentication token.");
  }

  return data.user.id;
}
