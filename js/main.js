/*
 * main.js
 *
 * Library/Application Support/Adobe/CEP/extensions/com.blastframe/js/main.js
 */

(function () {
  "use strict";

  const csInterface = new CSInterface();
  const auditButton = document.getElementById("audit-button");
  const copyButton = document.getElementById("copy-button");
  const statusDiv = document.getElementById("status");
  const outputArea = document.getElementById("textArea"); // <textarea/>

  function framesToSeconds(frames, frameRate) {
    if (!frameRate || frameRate === 0) return "0.00 s";
    const seconds = frames / frameRate;
    return seconds.toFixed(2) + " s";
  }

  function esc(s) {
    return (s || "").replace(/[*_`~]/g, "\\$&"); // light Markdown escaping
  }

  function generateMarkdown(data) {
    const frameRate = data.frameRate;
    const acts = [
      { name: "THE RACE", start: 0, end: 449, clips: [] },
      { name: "REJECTION", start: 449, end: 606, clips: [] },
      { name: "RESCUE", start: 606, end: 1284, clips: [] },
      { name: "THE HERO", start: 1284, end: 1440, clips: [] },
    ];

    const all = (data.clips || []).filter((c) => c && (c.text || c.name));
    let idx = 1;
    for (const clip of all) {
      let placed = false;
      for (const act of acts) {
        if (clip.startFrame >= act.start && clip.startFrame < act.end) {
          act.clips.push({ ...clip, number: idx++ });
          placed = true;
          break;
        }
      }
      if (!placed) acts[acts.length - 1].clips.push({ ...clip, number: idx++ });
    }

    let md = `# CYBERNETIC LIST\n\n`;
    for (const act of acts) {
      if (!act.clips.length) continue;
      const durF = act.end - act.start;
      md += `---\n\n## ${act.name}\n\n`;
      md += `- **Start:** Frame ${act.start}\n`;
      md += `- **End:** Frame ${act.end}\n`;
      md += `- **Duration:** ${durF} frames (${framesToSeconds(
        durF,
        frameRate
      )})\n\n`;
      for (const c of act.clips) {
        const label = esc(c.text || c.name || "");
        md += `**${c.number}. ${label}**\n`;
        md += `  - **Start:** Frame ${c.startFrame}\n`;
        md += `  - **End:** Frame ${c.endFrame}\n`;
        md += `  - **Duration:** ${c.durationFrames} frames (${framesToSeconds(
          c.durationFrames,
          frameRate
        )})\n\n`;
      }
    }

    md += `---\n\n`;
    md += `## Totals\n`;
    md += `- **Clips found:** ${all.length}\n`;
    md += `- **Total duration:** ${
      data.totalDurationFrames
    } frames (${framesToSeconds(
      data.totalDurationFrames,
      frameRate
    )}) at ${frameRate.toFixed(3)} fps\n\n`;

    md += `---\n\n`;
    md += `### Important Note About Graphics Clips\n\n`;
    md += `Native Premiere Pro Graphics/Text clips **do not expose their actual text content** through the scripting API. The visible text you see in Premiere cannot be accessed programmatically.\n\n`;
    md += `**Solution:** Rename your Graphics clips in the timeline with descriptive names (e.g., "Title: The Race Begins"). This script will use the clip name as the text value.\n\n`;
    md += `**Alternative:** For programmatic text access, use MOGRTs (Motion Graphics Templates) with **Source Text** parameters exposed, instead of native Graphics clips.\n`;
    return md;
  }

  function onGenerateAudit() {
    outputArea.value = "";
    statusDiv.className = "";
    statusDiv.textContent = "Executing script...";

    csInterface.evalScript("getSequenceAudit()", function (result) {
      try {
        if (typeof result === "string" && result.indexOf("Error:") === 0) {
          statusDiv.className = "error";
          statusDiv.textContent = result;
          outputArea.value = result;
          return;
        }
        const data = JSON.parse(result);
        if (data.error) {
          statusDiv.className = "error";
          statusDiv.textContent = data.error;
          outputArea.value = data.error;
          return;
        }
        const markdown = generateMarkdown(data);
        statusDiv.textContent = `Audit complete: Found ${data.clips.length} clips.`;
        outputArea.value = markdown; // textarea content
        console.log("Audit Data:", data);
      } catch (e) {
        statusDiv.className = "error";
        statusDiv.textContent =
          "A JavaScript error occurred during processing.";
        outputArea.value = `Error: Could not parse ExtendScript result.\nRaw result: ${result}\nException: ${e.message}`;
        console.error("CEP Error:", e);
      }
    });
  }

  function onCopyMarkdown() {
    try {
      outputArea.select();
      document.execCommand("copy");
      statusDiv.className = "";
      statusDiv.textContent = "Markdown copied to clipboard.";
    } catch (e) {
      statusDiv.className = "error";
      statusDiv.textContent =
        "Copy failed. Select the text and press ⌘/Ctrl+C.";
    }
  }

  auditButton.addEventListener("click", onGenerateAudit);
  copyButton.addEventListener("click", onCopyMarkdown);
})();
