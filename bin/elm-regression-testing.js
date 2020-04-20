#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const commander_1 = require("commander");
const ora = require("ora");
const node_elm_compiler_1 = require("node-elm-compiler");
const path = require("path");
const fs = require("fs");
const tmp = require("tmp");
const ELM_PACKAGE_NAME = "jgrenat/regression-testing";
const program = new commander_1.Command();
program
    .version("0.0.1")
    .arguments("<input>")
    .option("-o, --output <path>", "Path to the Elm file that will be generated containing the tests data", "./tests/GeneratedRegressionTestData.elm")
    .option("-m, --module <name>", "Name of the generated module. If not provided, we will try to extract it from the output file path")
    .action((inputPath, cmdObj) => {
    let temporaryDirectory;
    const projectGenerationSpinner = ora("Creating a temporary project for compilation...").start();
    try {
        temporaryDirectory = generateTemporaryProjectForCompilation(inputPath);
        projectGenerationSpinner.succeed("Temporary project created for compilation");
    }
    catch (err) {
        console.error(err);
        projectGenerationSpinner.fail("Failed to create temporary project for compilation");
        return;
    }
    const compilationSpinner = ora("Compiling generator file...").start();
    const temporaryCompiledFilePath = path.join(temporaryDirectory.name, "generated.js");
    node_elm_compiler_1.compile([path.join(process.cwd(), inputPath)], {
        output: temporaryCompiledFilePath,
        cwd: temporaryDirectory.name
    }).on("close", function (exitCode) {
        const options = cmdObj.opts();
        if (exitCode !== 0) {
            compilationSpinner.fail("Error when trying to compile the generator file");
            temporaryDirectory.removeCallback();
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
        if (!app.ports || !app.ports.outputPort) {
            testsGenerationSpinner.fail("Unable to find the `outputPort` port. You have to expose one with the proper name: port outputPort : Encode.Value -> Cmd msg");
            temporaryDirectory.removeCallback();
            return;
        }
        app.ports.outputPort.subscribe((message) => {
            if (message.type === "error") {
                testsGenerationSpinner.fail("Error when generating tests: " + message.error);
                temporaryDirectory.removeCallback();
                return;
            }
            testsGenerationSpinner.succeed("Tests generated");
            const saveFileSpinner = ora("Generating output file...").start();
            fs.writeFile(options.output, message.fileContent, err => {
                if (err) {
                    saveFileSpinner.fail("Unable to save the output file:");
                    console.error(err);
                    temporaryDirectory.removeCallback();
                    return;
                }
                saveFileSpinner.succeed("Output file generated: " + options.output);
                temporaryDirectory.removeCallback();
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
        const isFirstLetterUppercase = firstLetter >= "A" && firstLetter <= "Z";
        if (isFirstLetterUppercase) {
            moduleNameParts.push(parts[i]);
        }
        else {
            break;
        }
    }
    return moduleNameParts.join(".");
}
function generateTemporaryProjectForCompilation(inputFile) {
    let elmJson;
    try {
        elmJson = fs.readFileSync(path.join(process.cwd(), "elm.json"), {
            encoding: "utf8"
        });
    }
    catch (err) {
        throw "This script should be called from the directory that contains your elm.json file and should have read access to it.";
    }
    let parsedElmJson;
    try {
        parsedElmJson = JSON.parse(elmJson);
        if (!parsedElmJson ||
            !parsedElmJson["test-dependencies"] ||
            !parsedElmJson["test-dependencies"].direct ||
            !parsedElmJson["test-dependencies"].direct ||
            !parsedElmJson.dependencies ||
            !parsedElmJson.dependencies.direct) {
            throw new Error();
        }
    }
    catch (err) {
        throw "Your elm.json contains an invalid JSON format, run `elm make` to have more detailed errors.";
    }
    if (!parsedElmJson["test-dependencies"].direct[ELM_PACKAGE_NAME] &&
        !parsedElmJson.dependencies.direct[ELM_PACKAGE_NAME]) {
        throw `Add ${ELM_PACKAGE_NAME} as a test dependency of your project by running \`elm-test install ${ELM_PACKAGE_NAME}\``;
    }
    if (parsedElmJson.dependencies.direct[ELM_PACKAGE_NAME]) {
        console.warn(`${ELM_PACKAGE_NAME} is a project dependency of your project, you should probably add it as test dependency instead by running \`elm-test install ${ELM_PACKAGE_NAME}\``);
    }
    const packageVersion = parsedElmJson["test-dependencies"].direct[ELM_PACKAGE_NAME] ||
        parsedElmJson.dependencies.direct[ELM_PACKAGE_NAME];
    delete parsedElmJson["test-dependencies"].direct[ELM_PACKAGE_NAME];
    parsedElmJson.dependencies.direct[ELM_PACKAGE_NAME] = packageVersion;
    parsedElmJson["source-directories"] = parsedElmJson["source-directories"].map(sourcePath => path.join(process.cwd(), sourcePath));
    // Generate a new project in the temporary folder
    let temporaryDirectory;
    try {
        temporaryDirectory = tmp.dirSync();
        fs.writeFileSync(path.join(temporaryDirectory.name, "elm.json"), JSON.stringify(parsedElmJson));
        return temporaryDirectory;
    }
    catch (err) {
        console.error(err);
        if (temporaryDirectory && temporaryDirectory.removeCallback) {
            try {
                tmp.removeCallback();
            }
            catch (_) { }
        }
        throw "Impossible to generate the temporary project for compilation";
    }
}
program.parse(process.argv);
