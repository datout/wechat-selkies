/**
 * IME cursor follow helper for Selkies dashboards.
 *
 * This does NOT read the remote app's caret position (not available in browser).
 * It simply keeps Selkies' hidden IME input element near the user's last pointer
 * position so Windows/macOS IME candidate UI appears close to where you clicked.
 */
(() => {
  if (window.__selkiesImeCursorFollowInstalled) return;
  window.__selkiesImeCursorFollowInstalled = true;

  let lastX = Math.round(window.innerWidth / 2);
  let lastY = Math.round(window.innerHeight / 2);

  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));

  function updateFromEvent(e) {
    if (typeof e.movementX === "number" && typeof e.movementY === "number" && document.pointerLockElement) {
      lastX = clamp(lastX + e.movementX, 0, window.innerWidth - 1);
      lastY = clamp(lastY + e.movementY, 0, window.innerHeight - 1);
      return;
    }
    if (typeof e.clientX === "number" && typeof e.clientY === "number") {
      lastX = clamp(e.clientX, 0, window.innerWidth - 1);
      lastY = clamp(e.clientY, 0, window.innerHeight - 1);
    }
  }

  function isInputLike(el) {
    if (!el) return false;
    const tag = (el.tagName || "").toLowerCase();
    return tag === "textarea" || (tag === "input" && (el.type === "text" || el.type === "" || el.type === "search" || el.type === "password"));
  }

  function looksLikeHiddenIme(el) {
    try {
      const cs = window.getComputedStyle(el);
      const w = el.offsetWidth || 0;
      const h = el.offsetHeight || 0;
      const tiny = (w <= 6 && h <= 6);
      const invisible = (cs.opacity === "0" || cs.visibility === "hidden");
      const left = parseInt(cs.left || "0", 10);
      const top = parseInt(cs.top || "0", 10);
      const offscreen = (left <= -1000 || top <= -1000);
      const peNone = cs.pointerEvents === "none";
      return (tiny || invisible || offscreen) && peNone;
    } catch (_) {
      return false;
    }
  }

  function pickImeElement(hintEl) {
    if (isInputLike(hintEl)) return hintEl;
    const ae = document.activeElement;
    if (isInputLike(ae)) return ae;

    const candidates = Array.from(document.querySelectorAll("textarea, input"));
    if (!candidates.length) return null;

    const hidden = candidates.filter(looksLikeHiddenIme);
    if (hidden.length) return hidden[0];

    candidates.sort((a, b) => ((a.offsetWidth * a.offsetHeight) - (b.offsetWidth * b.offsetHeight)));
    return candidates[0];
  }

  function moveImeElement(el) {
    if (!el) return;
    el.style.position = "fixed";
    el.style.left = `${lastX}px`;
    el.style.top = `${lastY}px`;
    el.style.width = "1px";
    el.style.height = "1px";
    el.style.opacity = "0";
    el.style.pointerEvents = "none";
    el.style.zIndex = "2147483647";
    el.style.margin = "0";
    el.style.padding = "0";
    el.style.fontSize = "16px";
    el.style.lineHeight = "16px";
  }

  function align(hintEl) {
    const el = pickImeElement(hintEl);
    moveImeElement(el);
  }

  window.addEventListener("pointermove", updateFromEvent, { passive: true });
  window.addEventListener("mousemove", updateFromEvent, { passive: true });

  window.addEventListener(
    "touchstart",
    (e) => {
      if (e.touches && e.touches[0]) {
        lastX = clamp(e.touches[0].clientX, 0, window.innerWidth - 1);
        lastY = clamp(e.touches[0].clientY, 0, window.innerHeight - 1);
      }
    },
    { passive: true }
  );

  window.addEventListener(
    "touchmove",
    (e) => {
      if (e.touches && e.touches[0]) {
        lastX = clamp(e.touches[0].clientX, 0, window.innerWidth - 1);
        lastY = clamp(e.touches[0].clientY, 0, window.innerHeight - 1);
      }
    },
    { passive: true }
  );

  window.addEventListener("compositionstart", (e) => align(e.target), true);
  window.addEventListener("compositionupdate", (e) => align(e.target), true);
  window.addEventListener("focusin", (e) => align(e.target), true);

  setInterval(() => align(null), 1000);
})();
