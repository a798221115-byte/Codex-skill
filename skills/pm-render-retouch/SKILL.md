---
name: pm-render-retouch
description: "Use for project-manager rendering retouch workflows: 项目经理P图, 效果图实景去杂物, 即梦去杂物, site-photo cleanup, high-resolution upscale, AI融图 handoff, Cowart product fusion, and product-to-scene lighting or perspective blending while preserving the real scene and product details."
---

# PM Render Retouch

## Purpose

Use this skill to run a repeatable效果图 workflow for project-manager site photos: remove clutter from real-site images with Dreamina, let the user choose a cleanup candidate, upscale the selected image, then guide manual AI融图 and Cowart image-2 fusion.

Keep the workflow conservative. The goal is not to redesign the site or product; it is to remove specified clutter, preserve the original scene, and make the placed product blend naturally through light, perspective, color temperature, contact shadows, and edge integration.

## Workflow

1. Collect the source site image or images from the user.
2. Ask whether each image needs object-removal changes beyond the default list. If the user gives no override, use the default cleanup prompt.
3. Before submitting paid Dreamina work, run:

```powershell
dreamina image2image -h
dreamina image_upscale -h
```

4. Tell the user that Dreamina generation consumes credits before submitting real tasks.
5. For each source image, submit 4 separate cleanup candidates with `dreamina image2image`.
6. Record each command, source image, prompt, `submit_id`, and final status.
7. Query and download each candidate with `dreamina query_result --submit_id=<id> --download_dir=<project-output-dir>`.
8. Show the downloaded candidates to the user and wait for the user to choose one.
9. Upscale the selected candidate to 4k with `dreamina image_upscale --resolution_type=4k`.
10. If 4k fails because VIP access is unavailable, report the concrete Dreamina error and offer to retry at 2k.
11. Stop and ask the user to manually place the product in AI融图, mark up the desired placement if needed, and return one annotated composite image.
12. Since Cowart is not assumed to be callable from Codex, provide the Cowart/image-2 fusion prompt below for manual use. Wait for the Cowart result.
13. Inspect the final returned image for scene preservation, product preservation, and natural blending. Call out visible issues and suggest a revised Cowart prompt only if needed.

## Dreamina Cleanup

Default removal objects:

```text
电动自行车、汽车、自行车、垃圾桶、手推车、柜子、杂物、人
```

Default protected details:

```text
栏杆
```

Default cleanup prompt:

```text
把图片中的电动自行车、汽车、自行车、垃圾桶、手推车、柜子、杂物、人都去掉，其他细节保持不变，包括栏杆不要改变。
```

If the user names different items to remove or protect, update only those parts:

```text
把图片中的{remove_objects}都去掉，其他细节保持不变，包括{protected_details}不要改变。
```

Use the source image's apparent aspect ratio when setting `--ratio`. If uncertain, omit `--ratio` rather than guessing badly.

Typical cleanup command shape:

```powershell
dreamina image2image --images "<source-image>" --prompt "<cleanup-prompt>" --resolution_type=2k --poll 30
```

Submit 4 separate tasks per source image. Do not pass more than 10 images to one `image2image` command.

Treat a Dreamina submit as successful only when the response includes `submit_id` and `gen_status` is `querying` or `success`. If `gen_status` is `fail`, report `fail_reason`.

## Candidate Review

Download each successful result into a project-local output folder, preferably:

```text
<source-folder>\pm-render-retouch\<YYYYMMDD-HHMM>\cleanup-candidates\
```

Show the downloaded images with absolute paths. Ask the user to choose the candidate to upscale. Do not upscale until the user identifies the selected candidate.

## Upscale

Default upscale target is 4k:

```powershell
dreamina image_upscale --image "<selected-cleanup-image>" --resolution_type=4k --poll 30
```

Download the final upscale result into:

```text
<source-folder>\pm-render-retouch\<YYYYMMDD-HHMM>\upscaled\
```

If 4k fails due to VIP restrictions or another Dreamina error, report the exact failure and ask whether to retry at 2k.

## AI Fusion and Cowart Handoff

After the user receives the upscaled cleanup image, instruct them to place the product manually in AI融图 and return one annotated composite image. The annotation should make the intended product position clear, but the later fusion must not change the real scene or product details.

Give this Cowart/image-2 prompt for manual use:

```text
请只优化产品与实景之间的光影、透视、色温、接触阴影和边缘融合，让产品自然融入现场。不要改变实景场景细节，不要改变产品外观、结构、颜色、Logo、文字、比例和摆放位置；不要新增或删除物体。
```

If a specific product or scene has fragile details, append them explicitly, for example:

```text
保留栏杆、地面纹理、墙面文字、产品Logo和产品结构，不要改动它们。
```

## Final Quality Check

When the Cowart result is returned, inspect for:

- Scene details preserved: railings, ground texture, walls, signage, boundaries, perspective lines.
- Product details preserved: shape, proportions, color, logo, text, structure, placement.
- Blend quality: matching light direction, contact shadow, color temperature, edge softness, scale, and perspective.
- No new unwanted objects, deleted scene features, warped products, or changed annotations left in the final image.

If the result is acceptable, return it as the final image. If not, explain the issue briefly and provide a tightened Cowart prompt that targets only the failed blending aspect.
