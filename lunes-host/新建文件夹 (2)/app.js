const { execSync } = require('child_process');
const fs = require('fs');

console.log("🚀 Bootstrapping installation...");

if (fs.existsSync('./install.sh')) {
    console.log("Found install.sh, executing...");
    try {
        // Run install.sh, which will overwrite this app.js with the real one
        execSync('chmod +x install.sh && bash install.sh', { stdio: 'inherit' });
        console.log("Installation complete. The server will now restart to load the new configuration.");
        process.exit(0); 
    } catch (error) {
        console.error("Installation failed:", error);
        process.exit(1);
    }
} else {
    console.error("❌ install.sh not found! Please upload install.sh to the container.");
    // Keep alive to allow user to upload file
    setInterval(() => {}, 1000);
}
