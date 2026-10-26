const path = require('path');

module.exports = {
  entry: './src/main.ts', // Entry point, adjust if necessary.
  output: {
    filename: 'window.js',
    path: path.resolve(__dirname, 'dist'), // Output directory.
  },
  resolve: {
    extensions: ['.ts', '.js'], // Resolve both .ts and .js extensions.
  },
  module: {
    rules: [
      {
        test: /\.ts$/, // Apply ts-loader for ".ts" files.
        exclude: /node_modules/,
        use: {
          loader: 'ts-loader',
        },
      },
    ],
  },
  stats: { // Include detailed stats options for debugging.
    modules: true,
    orphanModules: true,
    reasons: true,
    usedExports: true,
  },
  devtool: 'source-map',
  mode: 'production', // Or "development".
};
