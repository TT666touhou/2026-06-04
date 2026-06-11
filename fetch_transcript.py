import sys
from youtube_transcript_api._cli import YouTubeTranscriptCli

try:
    cli = YouTubeTranscriptCli(["PpeCur6fEXc", "--languages", "zh-TW"])
    text = cli.run()
    with open("transcript.txt", "w", encoding="utf-8") as f:
        f.write(text)
    print("Success")
except Exception as e:
    print(f"Failed: {e}")
