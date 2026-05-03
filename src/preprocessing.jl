
const even_crop = (332, 716, 3796, 2668)
const odd_crop = (640, 712, 4096, 2792)

function preprocess_page(jp2_path::String)
	page_number = parse(Int, match(r"_(\d+)\.[^.]+$", jp2_path).captures[1])
	is_even = iseven(page_number)

	raw_png = tempname() * ".png"
	run(pipeline(`sips -s format png $jp2_path --out $raw_png`, stdout = devnull))

	image = load(raw_png)

	x1, y1, x2, y2 = is_even ? even_crop : odd_crop
	cropped = image[y1:y2, x1:x2]

	upright = is_even ? rotl90(cropped) : rotr90(cropped)

	output_path = tempname() * "_cropped.png"
	save(output_path, upright)
	rm(raw_png; force = true)
	return output_path
end

