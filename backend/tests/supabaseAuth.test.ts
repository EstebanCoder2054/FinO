import { describe, expect, it } from "vitest";
import { ApiError } from "../src/api/errors.js";
import { getAuthenticatedUserId } from "../src/auth/supabaseAuth.js";

describe("getAuthenticatedUserId", () => {
  it("returns the verified Supabase user ID", async () => {
    const userId = await getAuthenticatedUserId("valid-token", {
      auth: {
        getUser: async () => ({
          data: {
            user: {
              id: "user-123"
            }
          },
          error: null
        })
      }
    });

    expect(userId).toBe("user-123");
  });

  it("rejects invalid tokens", async () => {
    await expect(
      getAuthenticatedUserId("invalid-token", {
        auth: {
          getUser: async () => ({
            data: {
              user: null
            },
            error: new Error("invalid")
          })
        }
      })
    ).rejects.toBeInstanceOf(ApiError);
  });
});
