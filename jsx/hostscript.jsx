/*
 * hostscript.jsx
 * 
 * Library/Application Support/Adobe/CEP/extensions/com.blastframe/jsx/hostscript.jsx
 */

#include "../js/json2.js"
#include "../js/polyfills.js"

/*
* hostscript.jsx
* Runs inside Adobe Premiere Pro. Traverses the active sequence,
* extracts clip data, and returns it as a JSON string.
*
* IMPORTANT LIMITATION:
* Native Premiere Pro Graphics/Text clips do NOT expose their actual text content
* through the ExtendScript API. The "Source Text" property returns placeholder
* Unicode characters, not the visible text.
* 
* SOLUTION: Name your Graphics clips with the text you want to appear in the audit.
* The script will use the clip name as the text value for Graphics clips.
*/

function __bf_probeJSON() {
    return (typeof JSON !== 'undefined' && typeof JSON.stringify === 'function') ? 'ok' : 'no-json';
}

function getSequenceAudit() {
    try {
        if (!app.project.activeSequence) {
            return JSON.stringify({ error: "Error: No active sequence found. Please open a sequence in the timeline." });
        }

        var seq = app.project.activeSequence;

        // ---- time math ----
        var TICKS_PER_SECOND = 254016000000;
        var ticksPerFrame = Number(seq.timebase);
        if (!ticksPerFrame || isNaN(ticksPerFrame) || ticksPerFrame <= 0) {
            ticksPerFrame = Math.round(TICKS_PER_SECOND / 24); // fallback
        }
        var frameRate = TICKS_PER_SECOND / ticksPerFrame;
        var totalDurationFrames = Math.round(Number(seq.end) / ticksPerFrame);

        function trimToString(v) {
            if (v === undefined || v === null) return "";
            return ("" + v).replace(/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g, "");
        }

        // Text extraction function
        function getTextFromClip(clip) {
            var clipName = trimToString(clip.name);
            
            // Strategy 1: Check for MOGRT (Essential Graphics with exposed parameters)
            if (typeof clip.getMGTComponent === "function") {
                try {
                    var moComp = clip.getMGTComponent();
                    if (moComp && moComp.properties && moComp.properties.numItems) {
                        // Try common text parameter names
                        var commonNames = ["Source Text", "Text", "source text", "text", "Main Title", "Title"];
                        for (var n = 0; n < commonNames.length; n++) {
                            if (typeof moComp.properties.getParamForDisplayName === "function") {
                                var param = moComp.properties.getParamForDisplayName(commonNames[n]);
                                if (param && typeof param.getValue === "function") {
                                    var val = param.getValue();
                                    if (val !== undefined && val !== null) {
                                        var valStr = trimToString(val);
                                        // Check if this is actual readable text (not a placeholder character)
                                        if (valStr.length > 0 && valStr.charCodeAt(0) >= 32 && valStr.charCodeAt(0) <= 126) {
                                            return valStr;
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Scan all MOGRT properties
                        for (var i = 0; i < moComp.properties.numItems; i++) {
                            var prop = moComp.properties[i];
                            if (prop && typeof prop.getValue === "function") {
                                var dn = prop.displayName ? ("" + prop.displayName).toLowerCase() : "";
                                if (dn.indexOf("text") !== -1 || dn.indexOf("title") !== -1) {
                                    var value = prop.getValue();
                                    if (value !== undefined && value !== null) {
                                        var valueStr = trimToString(value);
                                        // Check for readable text
                                        if (valueStr.length > 0 && valueStr.charCodeAt(0) >= 32 && valueStr.charCodeAt(0) <= 126) {
                                            return valueStr;
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch (e) {
                    // Continue to next strategy
                }
            }
            
            // Strategy 2: For all other clips, use the clip name
            // Return the clip name even if it's just "Graphic"
            return clipName;
        }

        var clipsData = [];
        var vTracks = seq.videoTracks;
        var trackCount = vTracks.numTracks;

        // Loop through ALL video tracks
        for (var i = 0; i < trackCount; i++) {
            var track = vTracks[i];
            var clipCount = track.clips.numItems;

            // Loop through ALL clips in this track
            for (var j = 0; j < clipCount; j++) {
                var clip = track.clips[j];

                var text = getTextFromClip(clip);
                
                // Skip clips with no text (but keep all other clips)
                if (!text || text.length === 0) continue;

                var startSec = clip.start.seconds;
                var endSec   = clip.end.seconds;
                var startF   = Math.round(startSec * frameRate);
                var endF     = Math.round(endSec   * frameRate);

                clipsData.push({
                    text: text,
                    name: trimToString(clip.name),
                    startFrame: startF,
                    endFrame: endF,
                    durationFrames: Math.max(0, endF - startF),
                    trackIndex: i + 1
                });
            }
        }

        clipsData.sort(function(a, b){ return a.startFrame - b.startFrame; });

        return JSON.stringify({
            frameRate: frameRate,
            totalDurationFrames: totalDurationFrames,
            clips: clipsData
        });

    } catch (e) {
        return "Error: An ExtendScript error occurred: " + e.message;
    }
}

// Make the function available to the CEP panel
getSequenceAudit;