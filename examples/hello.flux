glyph greet [
    emit "hello from flux\n".
]

root main [
    loop 1 call greet.
    done 0.
]
