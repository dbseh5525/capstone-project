# Entrance assets

Generated using the built-in image_gen tool. Original outputs are preserved outside the project; the final PNGs are copied into the asset directories.

## assets/room/entrance_background.png

Reference: assets/room/room_background.png

Prompt:
Use case: stylized-concept. Create a matching portrait 1024x1536 mobile pet game entrance background using the reference's warm cream, honey wood, soft painted illustration style. Front-facing apartment entry hallway, one closed wooden entrance door centered horizontally, door bottom at 55% of image height, simple small shoe cabinet far left. Lower 45% clear warm wood floor for animated pet. No dogs, people, text, UI, watermark. Full opaque background. Keep the center door visible when sides are cropped. This is the entrance of the same cozy room.

## assets/dog/baby_wait.png

Reference: assets/dog/baby_idle.png

Initial prompt:
Use case: identity-preserve. Edit this pet game sprite into a patiently sitting waiting pose viewed from three-quarter rear, facing away toward upper right as if watching a front door. Preserve same fluffy white baby Pomeranian, pink inner ears, warm soft painted illustration style. Full body and fluffy curled tail visible, centered on square canvas, dog occupies 75% of canvas. Deliver actual transparent PNG alpha background, zero background artwork, no checkerboard pattern, no floor, no shadow, no text. Background must be truly transparent not painted transparency checkerboard.

The initial output had a baked-in checkerboard. The final output uses this correction prompt:
Background extraction edit: Remove all gray and white checkerboard background around the dog. The previous result was RGB with checkerboard baked in, unusable. Output MUST be RGBA PNG with alpha=0 outside dog and preserved white dog opaque. Keep exact dog pose identity and fur. Do not draw checkerboard or solid background. Actual transparent cutout required.

Validation: final image is Format32bppArgb, corner alpha is 0; visually inspected. Waiting sprite is used for the baby stage. Other stages retain their own appearance. Greeting now animates only the tail region of the idle sprite and shows three heart cycles before returning to the room. Whole-sprite tail frames, greeting bounce, breathing scale and greeting transition scale were removed to keep the body still. A pixel comparison test verifies the face, torso and paws do not change while the tail moves.
