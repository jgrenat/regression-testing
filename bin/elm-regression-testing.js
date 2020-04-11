"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const commander_1 = require("commander");
const ora = require("ora");
const node_elm_compiler_1 = require("node-elm-compiler");
const program = new commander_1.Command();
const os = require("os");
const path = require("path");
const fs = require("fs");
program
    .version("0.0.1")
    .arguments("<input>")
    .option("-o, --output <path>", "Path to the Elm file that will be generated containing the tests data", "./tests/GeneratedRegressionTestData.elm")
    .option("-m, --module <name>", "Name of the generated module. If not provided, we will try to extract it from the output file path")
    .action((inputPath, cmdObj) => {
    const temporaryCompiledFilePath = path.join(os.tmpdir(), "generated.js");
    const compilationSpinner = ora("Compiling generator file...").start();
    node_elm_compiler_1.compile([inputPath], { output: temporaryCompiledFilePath }).on("close", function (exitCode) {
        const options = cmdObj.opts();
        if (exitCode !== 0) {
            compilationSpinner.fail("Error when trying to compile the generator file");
            return;
        }
        compilationSpinner.succeed("Generator file compiled");
        const testsGenerationSpinner = ora("Generating tests...").start();
        const { Elm } = require(temporaryCompiledFilePath);
        const app = Elm.RegressionTestGenerator.init({
            flags: {
                moduleName: options.module || extractModuleFromOutputPath(options.output)
            }
        });
        app.ports.outputPort.subscribe((message) => {
            if (message.type === "error") {
                testsGenerationSpinner.fail("Error when generating tests: " + message.error);
                return;
            }
            testsGenerationSpinner.succeed("Tests generated");
            const saveFileSpinner = ora("Generating output file...").start();
            fs.writeFile(options.output, message.fileContent, err => {
                if (err) {
                    saveFileSpinner.fail("Unable to save the output file:");
                    console.error(err);
                    return;
                }
                saveFileSpinner.succeed("Output file generated: " + options.output);
            });
        });
    });
});
function extractModuleFromOutputPath(outputPath) {
    const parts = outputPath
        .replace(".elm", "")
        .split("/")
        .filter(a => !!a);
    const moduleNameParts = [];
    for (let i = parts.length - 1; i >= 0; i--) {
        const firstLetter = parts[i][0];
        const isFirstLetterUppercase = firstLetter >= 'A' && firstLetter <= 'Z';
        if (isFirstLetterUppercase) {
            moduleNameParts.push(parts[i]);
        }
    }
    return moduleNameParts.join('.');
}
program.parse(process.argv);
