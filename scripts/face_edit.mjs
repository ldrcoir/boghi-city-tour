import ZAI from 'z-ai-web-dev-sdk';
import fs from 'fs';

const jobs = [
  {
    in: '/home/z/my-project/scripts/face_edit/boghi_mag.png',
    out: '/home/z/my-project/scripts/face_edit/boghi_ai.png',
    size: '1152x864',
    prompt: `Turn this red hatchback into a living cartoon car character like Pixar Cars: repaint the white windshield band as a cute FACE with two BIG expressive oval eyes (white sclera, large shiny dark-blue pupils with white highlights, thin dark outlines) sitting on the windshield, friendly raised eyebrows, and paint a BIG happy open-mouth smile with white teeth on the front bumper between the headlights. Keep the red car body, wheels, headlights, windows, mirrors, grille, yellow badge and the flat magenta background EXACTLY unchanged. Only add the face.`,
  },
  {
    in: '/home/z/my-project/scripts/face_edit/icon_mag.png',
    out: '/home/z/my-project/scripts/face_edit/icon_ai.png',
    size: '1024x1024',
    prompt: `This is a game app icon of a cute red car character (three-quarter front view). Make the face beautiful like the approved concept: two BIG glossy round eyes with dark navy pupils and bright white highlights on the white windshield area, thin dark outline, happy friendly look, and a BIG joyful open smile with white teeth on the front bumper below the grille. Add a small golden star on the roof. Keep the red body, white roof, wheels, lights and the flat magenta background EXACTLY unchanged. Only improve the face and add the star.`,
  },
  {
    in: '/home/z/my-project/scripts/face_edit/pride_mag.png',
    out: '/home/z/my-project/scripts/face_edit/pride_ai.png',
    size: '1152x864',
    prompt: `This red rally hatchback must become a living racing car character: on the windshield add two SHARP determined racing eyes (white sclera, dark navy pupils, angled aggressive look like a determined racer, thin dark outlines), no smile but a confident thin grin on the front bumper. Also remove all small white speckle dots and stains from the red body paint so the paint is clean glossy red. Keep body shape, wheels, spoiler, headlights, windows and the flat magenta background EXACTLY unchanged.`,
  },
];

const zai = await ZAI.create();
for (const j of jobs) {
  const b64 = fs.readFileSync(j.in).toString('base64');
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const r = await zai.images.generations.edit({
        prompt: j.prompt,
        images: [{ url: `data:image/png;base64,${b64}` }],
        size: j.size,
      });
      fs.writeFileSync(j.out, Buffer.from(r.data[0].base64, 'base64'));
      console.log('OK', j.out);
      break;
    } catch (e) {
      console.error(`attempt ${attempt} failed:`, e.message);
      if (attempt === 3) process.exit(1);
      await new Promise((s) => setTimeout(s, 2000 * attempt));
    }
  }
}
