"""
CSYE 6225 - Assignment 4: Introduction to IaC with Packer and Terraform

Prompt Optimizer API (lite) - cleans, formats, and lightly enhances
AI text prompts. This is a deliberately small "v0" version; later
assignments in this course will build on it.

Do NOT modify this file. You will build this exact application into
a Packer AMI and deploy it with Terraform.
"""

import re
from flask import Flask, jsonify, request

app = Flask(__name__)

APP_NAME = "prompt-optimizer"
APP_VERSION = "0.1.0"

# In-memory request counter. Resets whenever the process restarts;
# that's expected and fine for this lite version.
_request_count = 0

# Small, fixed abbreviation dictionary used by /enhance.
# Deliberately simple and deterministic for grading purposes.
_ABBREVIATIONS = {
    "pls": "please",
    "plz": "please",
    "u": "you",
    "asap": "as soon as possible",
    "w/": "with",
    "info": "information",
}

_ENHANCEMENT_SUFFIX = " Be concise and specific."


def _count_request():
    global _request_count
    _request_count += 1


def clean_prompt(text: str) -> str:
    """Strip leading/trailing whitespace, collapse internal whitespace,
    and remove non-printable control characters."""
    # Remove control characters (except normal space, which whitespace
    # collapsing below will handle).
    text = "".join(ch for ch in text if ch == " " or not (0 <= ord(ch) < 32))
    # Collapse any run of whitespace (spaces, tabs, newlines) into a single space.
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def format_prompt(text: str) -> str:
    """Capitalize the first letter and ensure the prompt ends with
    terminal punctuation."""
    text = text.strip()
    if not text:
        return text
    if text[0].isalpha():
        text = text[0].upper() + text[1:]
    if text[-1] not in ".!?":
        text = text + "."
    return text


def enhance_prompt(text: str) -> str:
    """Expand a small set of known abbreviations (whole-word, case-insensitive)
    and append a light clarifying instruction if not already present."""

    def replace(match: "re.Match") -> str:
        word = match.group(0)
        lower = word.lower()
        replacement = _ABBREVIATIONS[lower]
        # Preserve capitalization of the first letter if the original was capitalized.
        if word[0].isupper():
            replacement = replacement[0].upper() + replacement[1:]
        return replacement

    pattern = r"\b(" + "|".join(re.escape(k) for k in _ABBREVIATIONS) + r")\b"
    text = re.sub(pattern, replace, text, flags=re.IGNORECASE)

    if _ENHANCEMENT_SUFFIX.strip().lower() not in text.lower():
        text = text.rstrip() + _ENHANCEMENT_SUFFIX

    return text


@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "app": APP_NAME,
        "version": APP_VERSION,
        "routes": [
            "GET /healthcheck",
            "GET /version",
            "GET /stats",
            "POST /clean",
            "POST /format",
            "POST /enhance",
            "POST /optimize",
            "POST /analyze",
        ],
    }), 200


@app.route("/healthcheck", methods=["GET"])
def healthcheck():
    return jsonify({"status": "ok"}), 200


@app.route("/version", methods=["GET"])
def version():
    return jsonify({"app": APP_NAME, "version": APP_VERSION}), 200


@app.route("/stats", methods=["GET"])
def stats():
    return jsonify({"requests_processed": _request_count}), 200


@app.route("/clean", methods=["POST"])
def clean():
    _count_request()
    data = request.get_json(force=True, silent=True) or {}
    original = data.get("prompt", "")
    return jsonify({"original": original, "cleaned": clean_prompt(original)}), 200


@app.route("/format", methods=["POST"])
def format_route():
    _count_request()
    data = request.get_json(force=True, silent=True) or {}
    original = data.get("prompt", "")
    return jsonify({"original": original, "formatted": format_prompt(original)}), 200


@app.route("/enhance", methods=["POST"])
def enhance():
    _count_request()
    data = request.get_json(force=True, silent=True) or {}
    original = data.get("prompt", "")
    return jsonify({"original": original, "enhanced": enhance_prompt(original)}), 200


@app.route("/optimize", methods=["POST"])
def optimize():
    _count_request()
    data = request.get_json(force=True, silent=True) or {}
    original = data.get("prompt", "")
    cleaned = clean_prompt(original)
    formatted = format_prompt(cleaned)
    enhanced = enhance_prompt(formatted)
    return jsonify({
        "original": original,
        "cleaned": cleaned,
        "formatted": formatted,
        "enhanced": enhanced,
        "optimized": enhanced,
    }), 200


@app.route("/analyze", methods=["POST"])
def analyze():
    _count_request()
    data = request.get_json(force=True, silent=True) or {}
    text = data.get("prompt", "")
    char_count = len(text)
    word_count = len(text.split())
    estimated_tokens = max(1, round(char_count / 4)) if text else 0
    return jsonify({
        "char_count": char_count,
        "word_count": word_count,
        "estimated_tokens": estimated_tokens,
    }), 200


if __name__ == "__main__":
    # Listens on all interfaces so it's reachable from outside the EC2 instance.
    # Defaults to port 80 (used by the deployed systemd service, which runs as
    # root - see install_app.sh). For local testing without sudo/admin rights,
    # override with a higher port, e.g.: PORT=8080 python3 server.py
    import os
    port = int(os.environ.get("PORT", 80))
    app.run(host="0.0.0.0", port=port)
