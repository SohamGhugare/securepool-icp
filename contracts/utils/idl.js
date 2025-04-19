#!/usr/bin/env node

/**
 * This script generates the IDL files for the canisters.
 * Run it after making changes to the canister interfaces.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const CANISTERS = ['InsurancePool', 'InsurancePolicy'];
const OUTPUT_DIR = path.join(__dirname, '../../frontend/app/declarations');

// Create output directory if it doesn't exist
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Generate IDL for each canister
CANISTERS.forEach(canisterName => {
  console.log(`Generating IDL for ${canisterName}...`);
  
  try {
    // Run didc command to compile Motoko to Candid
    const didFile = path.join(OUTPUT_DIR, `${canisterName}.did`);
    execSync(`dfx generate ${canisterName}`, { stdio: 'inherit' });
    
    // Copy the generated Candid file to our declarations directory
    const generatedDidPath = `.dfx/local/canisters/${canisterName}/${canisterName}.did`;
    if (fs.existsSync(generatedDidPath)) {
      fs.copyFileSync(generatedDidPath, didFile);
      console.log(`Created ${didFile}`);
    } else {
      console.error(`Failed to find generated did file at ${generatedDidPath}`);
    }
    
    // Generate JavaScript bindings from Candid
    execSync(`didc bind -t js ${didFile} > ${path.join(OUTPUT_DIR, `${canisterName}.did.js`)}`, { stdio: 'inherit' });
    console.log(`Generated JS bindings for ${canisterName}`);
    
    // Generate TypeScript types from Candid
    execSync(`didc bind -t ts ${didFile} > ${path.join(OUTPUT_DIR, `${canisterName}.did.d.ts`)}`, { stdio: 'inherit' });
    console.log(`Generated TS types for ${canisterName}`);
  } catch (error) {
    console.error(`Error generating IDL for ${canisterName}:`, error.message);
  }
});

console.log('IDL generation complete!'); 