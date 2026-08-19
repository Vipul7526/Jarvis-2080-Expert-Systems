# JARVIS Reference Audit

## User-provided visual references

The supplied screenshots and video references consistently show a portrait mobile assistant interface centered on a luminous, particle-based spherical core. Key visual cues are a dark or translucent background, high-contrast neon cyan/blue or gold/yellow glow, a large centered orb, fine point-cloud particles, circular rings, orbiting arcs, and a compact listening/status label below the orb. Several references use a single centered microphone or voice trigger control below the status label. The desired experience should feel immersive without hiding the Android status/navigation areas or making controls too small for a phone.

The hacking-dashboard screenshots use a deliberately retro neon-green terminal aesthetic with a grid of tiles such as Bitcoin Miner, Headquarters Surveillance, Password Cracker, Nuclear Plant, Remote Connection, Advertisements, Interpol Database, and Program Console. This visual is being treated as a clearly labelled prank-only simulation, not as a real security or offensive tool.

## Browser audit of supplied YouTube links

- `_3_M7fh1I40`: YouTube Short titled “Jarvis source code link in GitHub #jarvis #python #mrbeast” by @DevloperSashank. Sandbox playback reported “Video unavailable”; the visible page metadata confirms a JARVIS coding/source-code theme.
- `Y2ns6PFaTm8`: the YouTube watch URL redirected to a Google anti-bot/interstitial page in the sandbox, so no reliable page text was available. The user-provided screenshot remains the visual reference for this item.
- `emfFxq_yXvA`: YouTube Short titled “Forget Jarvis… I’m Building ULTRON! 🤖🔥” by @neuralstack-p5d. Playback reported “Video unavailable”; metadata confirms an AI/automation visual theme.
- `V6kvapGV9qk`: YouTube Short titled “I Built a Real JARVIS to Control My Phone! 💀” by @jarvis_ai_spark. Playback reported “Video unavailable”; the title and user-provided screenshot reinforce the real phone-control and voice-command interaction goal.

## Initial implementation direction

Use a mobile-first dark glass interface with safe-area padding, a large responsive sphere that scales to available width, dynamic listening/processing/speaking states, a real microphone action, compact command transcript, and a bottom navigation or command-drawer pattern. Keep real hardware/device controls in clearly separated tabs. Put the prank dashboard behind a conspicuous simulation banner and keep it limited to local visual animation, fictional telemetry, and clearly fictional labels; it must not send packets, scan targets, crack passwords, control devices, or perform any offensive action.

## Public implementation references

The ElevenLabs UI Orb documentation describes a 3D animated orb with audio reactivity, custom colors, and agent-state visualization. It distinguishes idle, listening, and talking states and exposes normalized input/output volume controls, dynamic colors, deterministic seeds, resize debouncing, and lifecycle cleanup. These are useful design and engineering patterns for JARVIS, even though the implementation target here is Flutter rather than Three.js.

The public HordVoice Flutter repository shows a useful service-oriented organization for a voice assistant: separate speech, wake-word, emotion/avatar, spatial overlay, device monitoring, telephony, permission, external API, and reliability services. The relevant adaptation for JARVIS is to keep the visual layer modular and drive it from explicit assistant states, while keeping real permissions and device operations behind native/service boundaries.

## Additional public pattern cross-check

Additional public results reinforced the chosen direction: Flutter orb examples emphasize a single central reactive object rather than dense control panels; voice-first companions commonly combine voice and text in one surface; and Android assistant discussions favor transparent or frosted overlays with minimal persistent chrome. The redesign applies those patterns through a large central state-driven sphere, a compact text/voice composer, glass cards, and a bottom navigation bar that remains usable on smaller phones.

A safety distinction is intentional: the cyber deck is an isolated local visual simulator with a visible disclaimer, while device, terminal, GPS, authentication, and LAN mesh surfaces report only actual native/API results or explicit unavailable states.
