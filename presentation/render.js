#!/usr/bin/env node

/**
 * HyperNotch — Deterministic Frame-Stepped Video Exporter
 * Puppeteer + FFmpeg pipe (No real-time screen record, zero dropped frames)
 * Usage:
 *   node render.js [--aspect=16:9 | --aspect=9:16] [--fps=30] [--out=output.mp4]
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

async function render() {
  const puppeteer = require('puppeteer');

  const args = process.argv.slice(2);
  const aspectArg = args.find(a => a.startsWith('--aspect='))?.split('=')[1] || '16:9';
  const fpsArg = parseInt(args.find(a => a.startsWith('--fps='))?.split('=')[1] || '30', 10);
  const outFile = args.find(a => a.startsWith('--out='))?.split('=')[1] || `HyperNotch_Reel_${aspectArg.replace(':', 'x')}_${fpsArg}fps.mp4`;

  const is916 = aspectArg === '9:16';
  const width = is916 ? 1080 : 1920;
  const height = is916 ? 1920 : 1080;
  const durationSec = 15.0;
  const totalFrames = Math.round(durationSec * fpsArg);

  console.log(`\n========================================`);
  console.log(`🎬 HyperNotch Deterministic Video Renderer`);
  console.log(`Aspect: ${aspectArg} (${width}x${height})`);
  console.log(`Framerate: ${fpsArg} FPS`);
  console.log(`Duration: ${durationSec}s (${totalFrames} frames)`);
  console.log(`Target: ${outFile}`);
  console.log(`========================================\n`);

  // Launch headless Chrome
  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-web-security',
      '--allow-file-access-from-files',
      `--window-size=${width},${height}`
    ]
  });

  const page = await browser.newPage();
  await page.setViewport({ width, height, devicePixelRatio: 1 });

  const htmlPath = path.resolve(__dirname, 'kinetic_reel.html');
  await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle0' });

  // Switch aspect ratio if 9:16
  if (is916) {
    await page.evaluate(() => {
      const stage = document.getElementById('stage');
      if (stage && !stage.classList.contains('vertical-9-16')) {
        stage.classList.add('vertical-9-16');
      }
    });
  }

  // Hide the director control bar for clean video output
  await page.evaluate(() => {
    const bar = document.getElementById('director-bar');
    if (bar) bar.style.display = 'none';
    const hud = document.getElementById('director-hud');
    if (hud) hud.style.display = 'none';
    const stage = document.getElementById('stage');
    stage.style.transform = 'none';
    stage.style.position = 'fixed';
    stage.style.inset = '0';
  });

  // Spawn ffmpeg child process
  const ffmpeg = spawn('/opt/homebrew/bin/ffmpeg', [
    '-y',
    '-f', 'image2pipe',
    '-vcodec', 'png',
    '-r', String(fpsArg),
    '-i', '-',
    '-c:v', 'libx264',
    '-preset', 'slow',
    '-crf', '16',
    '-pix_fmt', 'yuv420p',
    path.resolve(__dirname, outFile)
  ]);

  ffmpeg.stderr.on('data', (d) => {
    // suppress ffmpeg spam, uncomment for debug:
    // process.stderr.write(d);
  });

  console.log(`▶ Starting deterministic frame capture...`);

  for (let frame = 0; frame < totalFrames; frame++) {
    const timeMs = (frame / fpsArg) * 1000;
    
    // Exact deterministic frame step
    await page.evaluate((ms) => {
      window.__SET_TIME__(ms);
    }, timeMs);

    const buffer = await page.screenshot({ type: 'png', omitBackground: true });
    ffmpeg.stdin.write(buffer);

    if (frame % 30 === 0 || frame === totalFrames - 1) {
      const pct = Math.round((frame / totalFrames) * 100);
      process.stdout.write(`\r[${pct}%] Frame ${frame + 1}/${totalFrames} (${(timeMs/1000).toFixed(2)}s) rendered...`);
    }
  }

  ffmpeg.stdin.end();

  await new Promise((resolve) => {
    ffmpeg.on('close', resolve);
  });

  await browser.close();

  // Mux BGM soundtrack if available
  const bgmPath = path.resolve(__dirname, 'audio/bgm/cat-walk.mp3');
  if (fs.existsSync(bgmPath)) {
    const rawVideo = path.resolve(__dirname, `raw_${outFile}`);
    fs.renameSync(path.resolve(__dirname, outFile), rawVideo);
    console.log(`\n🔊 Muxing soundtrack (${bgmPath})...`);
    const audioFfmpeg = spawn('/opt/homebrew/bin/ffmpeg', [
      '-y',
      '-i', rawVideo,
      '-i', bgmPath,
      '-t', String(durationSec),
      '-c:v', 'copy',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-af', `afade=t=out:st=${(durationSec - 0.6).toFixed(2)}:d=0.6`,
      path.resolve(__dirname, outFile)
    ]);
    await new Promise((res) => audioFfmpeg.on('close', res));
    try { fs.unlinkSync(rawVideo); } catch (e) {}
    console.log(`✅ Soundtrack successfully muxed!`);
  }

  console.log(`\n\n✅ Done! Video saved to: ${outFile}\n`);
}

render().catch(err => {
  console.error('Error during render:', err);
  process.exit(1);
});
