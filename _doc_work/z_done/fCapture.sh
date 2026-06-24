cat > ./bin/fCapture << 'EOF'
#!/bin/zsh
DIR="${0:A:h}"
"$DIR/../fCapture/.build/arm64-apple-macosx/release/fCapture" "$@"
EOF
chmod +x ./bin/fCapture
./bin/fCapture