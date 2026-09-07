# Feeding sprite

Final asset: `assets/dog/baby_eat.png`.
Generated and edited with the built-in image_gen tool, using `assets/dog/baby_idle.png` as the reference. Final file is RGBA with transparent corner alpha 0, and was checked in a rendered feeding scene.

## Generation prompt

Use case: identity-preserve. Edit the reference into one feeding animation frame for the exact same white baby Pomeranian. Keep the 1280x1280 square canvas, same dog body size and position, same tail at left, same paws planted at y=990, same soft painted fur and proportions. Change the neck and head pose: face toward the RIGHT in three-quarter side view, head bent DOWN to eat, muzzle near (1010,950), eyes looking down partly closed, mouth gently nibbling, ears tilt forward. Body and legs remain still and upright, only neck bends and head lowers, do not bow entire body. No food bowl, no food, no floor, no shadows, no text. Actual transparent RGBA PNG background with zero alpha outside dog, absolutely no painted checkerboard. Keep at least 100px transparent margin all around.

## Background correction prompts

The initial results contained a baked-in checkerboard. Two English extraction attempts were rejected during inspection:

Background extraction edit: Remove all gray and white checkerboard background around the dog. The previous result was RGB with checkerboard baked in, unusable. Output MUST be RGBA PNG with alpha=0 outside dog and preserved white dog opaque. Keep exact dog pose identity and fur. Keep original square canvas and exact dog placement and padding, do not crop or enlarge. Do not draw checkerboard or solid background. Actual transparent cutout required.

Background extraction edit: Remove all gray and white checkerboard background around the dog. The previous result was RGB with checkerboard baked in, unusable. Output MUST be RGBA PNG with alpha=0 outside dog and preserved white dog opaque. Keep exact dog pose identity and fur. Do not draw checkerboard or solid background. Actual transparent cutout required.

The final extraction used:

이 이미지의 강아지만 배경 제거해서 투명 PNG로 만들어줘. 체크무늬는 전부 지워줘. 강아지는 그대로 유지해줘.

## Animation integration

Transition refinement: removed the large head/neck mesh offsets before and after eating. The original poses now blend briefly at their fixed proportions; the small nibbling deformation during eating is unchanged.

Feeding lasts 4.2 seconds after walking to the bowl. The head lowers during the first 18%, nibbles during the middle, and rises during the final 20%. A smooth mesh deforms only the head region, keeping the body and paws stable. The baby uses the new lowered-head cutout blended with its idle pose; older stages retain their own sprite with the head deformation. The cutout is positioned to match the idle paw baseline and its muzzle meets the bowl. The previous whole-body rocking and floating feeding icon are removed.
