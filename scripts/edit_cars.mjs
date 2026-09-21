import ZAI from '/home/z/.bun/install/global/node_modules/z-ai-web-dev-sdk/dist/index.js';
import fs from 'fs';

const jobs = [
  {
    src: '/home/z/my-project/game/assets/sprites/dena_side.png',
    out: '/home/z/my-project/scripts/dena_race_raw.png',
    prompt: 'Repaint this white sedan car body to glossy bright fire-engine red with two parallel white racing stripes running along the hood, roof and trunk. Keep the wheels, windows, headlights, grille, mirrors, car shape, angle and proportions exactly identical. Isolated on a solid pure magenta #FF00FF background with no shadow.',
  },
  {
    src: '/home/z/my-project/game/assets/sprites/pejo_side.png',
    out: '/home/z/my-project/scripts/pejo_race_raw.png',
    prompt: 'Repaint this silver hatchback car body to glossy bright fire-engine red with two parallel white racing stripes running along the hood and roof. Keep the wheels, windows, headlights, grille, mirrors, car shape, angle and proportions exactly identical. Isolated on a solid pure magenta #FF00FF background with no shadow.',
  },
];

const zai = await ZAI.create();
for (const job of jobs) {
  const b64 = fs.readFileSync(job.src).toString('base64');
  const dataUrl = `data:image/png;base64,${b64}`;
  let done = false;
  for (let attempt = 1; attempt <= 3 && !done; attempt++) {
    try {
      const resp = await zai.images.generations.edit({
        prompt: job.prompt,
        images: [{ url: dataUrl }],
        size: '1344x768',
      });
      const out = resp?.data?.[0]?.base64;
      if (!out) throw new Error('no base64');
      fs.writeFileSync(job.out, Buffer.from(out, 'base64'));
      console.log('EDIT_OK', job.out);
      done = true;
    } catch (e) {
      console.error(`attempt ${attempt} failed for ${job.out}:`, e.message);
      if (attempt === 3) process.exitCode = 1;
      else await new Promise(r => setTimeout(r, 2000 * attempt));
    }
  }
}
console.log('ALL DONE');
