// YourTube: sideloads one zip to the TV's dev installer (replaces the current dev app).
// Reads ROKU_DEV_TARGET / ROKU_DEVPASSWORD from .env (gitignored). Never prints the password.
// Usage: node tools/yourtube/install-zip.js [path/to/YourTube-*.zip]   (default: newest in out/)
const path = require('path');
const fs = require('fs');
const rokuDeploy = require('roku-deploy');
const getEnvVars = require('../get-env-vars');

function newestZip(dir) {
    const zips = fs.readdirSync(dir)
        .filter((f) => /^YourTube-.*\.zip$/.test(f))
        .map((f) => ({ f, t: fs.statSync(path.join(dir, f)).mtimeMs }))
        .sort((a, b) => b.t - a.t);
    return zips.length ? path.join(dir, zips[0].f) : undefined;
}

(async () => {
    const config = getEnvVars(['ROKU_DEV_TARGET', 'ROKU_DEVPASSWORD']);
    const zip = path.resolve(process.argv[2] || newestZip(path.join(__dirname, '../../out')) || '');
    if (!fs.existsSync(zip)) {
        console.error('No YourTube zip found in out/. Build one with tools/yourtube-build.sh.');
        process.exit(1);
    }
    try {
        await rokuDeploy.publish({
            host: config.ROKU_DEV_TARGET,
            password: config.ROKU_DEVPASSWORD,
            outDir: path.dirname(zip),
            outFile: path.basename(zip),
            failOnCompileError: true,
        });
        console.log(`Installed ${path.basename(zip)} on ${config.ROKU_DEV_TARGET}`);
    } catch (error) {
        console.error(`Install failed: ${error.message || error}`);
        process.exit(1);
    }
})();
