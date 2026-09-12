import { ApiError } from "../api/errors.js";
import { getOptionalEnv, getRequiredEnv } from "../config/env.js";

type GladiaUploadResponse = {
  audio_url: string;
};

type GladiaTranscriptionJob = {
  id: string;
  result_url: string;
};

export async function uploadAudioToGladia(audio: Blob, filename: string): Promise<string> {
  const formData = new FormData();
  formData.append("audio", audio, filename);

  const response = await fetch(`${getGladiaBaseUrl()}/v2/upload`, {
    method: "POST",
    headers: {
      "x-gladia-key": getRequiredEnv("GLADIA_API_KEY")
    },
    body: formData
  });

  if (!response.ok) {
    throw new ApiError(502, "upstream_failure", "Could not upload audio for transcription.");
  }

  const data = (await response.json()) as GladiaUploadResponse;
  return data.audio_url;
}

export async function createGladiaTranscription(audioUrl: string): Promise<GladiaTranscriptionJob> {
  const response = await fetch(`${getGladiaBaseUrl()}/v2/transcription`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-gladia-key": getRequiredEnv("GLADIA_API_KEY")
    },
    body: JSON.stringify({
      audio_url: audioUrl,
      language_config: {
        languages: ["es"],
        code_switching: false
      },
      punctuation_enhanced: true
    })
  });

  if (!response.ok) {
    throw new ApiError(502, "upstream_failure", "Could not start transcription.");
  }

  return (await response.json()) as GladiaTranscriptionJob;
}

function getGladiaBaseUrl(): string {
  return getOptionalEnv("GLADIA_BASE_URL", "https://api.gladia.io").replace(/\/$/, "");
}
