const asdf = await WebAssembly.instantiateStreaming(fetch("zig-out/bin/webgame_v0.wasm"), {
    env: {
        consoleLog: (arg) => console.log(arg),
    }
});
// should print '2' twice, but it prints '2 0'
asdf.instance.exports.buggy(2);
