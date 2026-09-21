import ZAI from 'z-ai-web-dev-sdk';
import fs from 'fs';

const zai = await ZAI.create();
const b64 = fs.readFileSync('/home/z/my-project/scripts/face_edit/boghi_green.png').toString('base64');
const prompt = `This is a red hatchback car on a green screen. Give it a living cartoon character face exactly like Pixar Cars movies: the windshield becomes a FACE with two BIG expressive oval eyes (white sclera, large shiny dark-blue pupils with bright white highlights, thin black outlines) and friendly raised black eyebrows above them, and a BIG joyful open-mouth smile with white teeth painted on the front bumper between the headlights. CRITICAL: keep the exact same camera angle, same side-view pose, same car model, same red paint, wheels, headlights, mirrors, grille, yellow badge — do not move or reshape the car. Fill the entire background with flat pure green (#00FF00), no shadows on the green, no green reflections on the car body.`;
for (let attempt = 1; attempt <= 3; attempt++) {
  try {
    const r = await zai.images.generations.edit({
      prompt,
      images: [{ url: `data:image/png;base64,${b64}` }],
      size: '1152x864',
    });
    fs.writeFileSync('/home/z/my-project/scripts/face_edit/boghi_ai2.png', Buffer.from(r.data[0].base64, 'base64'));
    console.log('OK');
    break;
  } catch (e) {
    console.error('attempt', attempt, e.message);
    if (attempt === 3) process.exit(1);
    await new Promise((s) => setTimeout(s, 2000));
  }
}
