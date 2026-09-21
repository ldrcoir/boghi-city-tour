import ZAI from '/home/z/.bun/install/global/node_modules/z-ai-web-dev-sdk/dist/index.js';
import fs from 'fs';

const SRC = '/home/z/my-project/scripts/ustad_backup_v1.png';
const OUT = '/home/z/my-project/scripts/ustad_edit_raw.png';

const b64 = fs.readFileSync(SRC).toString('base64');
const dataUrl = `data:image/png;base64,${b64}`;

const prompt = `Remove this car mechanic's full black beard completely, replace with smooth clean-shaven chin, jaw and cheeks skin. Keep ONLY his thick black mustache above the lip. Keep absolutely everything else identical: same pose with raised wrench, same black cap, same happy smile, same teal green coveralls, same face identity, same lighting. Put a solid pure magenta #FF00FF background everywhere around the man.`;

const zai = await ZAI.create();
for (let attempt = 1; attempt <= 3; attempt++) {
  try {
    const resp = await zai.images.generations.edit({
      prompt,
      images: [{ url: dataUrl }],
      size: '1024x1024',
    });
    const out = resp?.data?.[0]?.base64;
    if (!out) throw new Error('no base64 in response');
    fs.writeFileSync(OUT, Buffer.from(out, 'base64'));
    console.log('EDIT_OK', OUT);
    process.exit(0);
  } catch (e) {
    console.error(`attempt ${attempt} failed:`, e.message);
    if (attempt === 3) process.exit(1);
    await new Promise(r => setTimeout(r, 2000 * attempt));
  }
}
