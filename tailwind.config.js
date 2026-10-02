// Builds assets/app.css from the classes used in the PHP pages:
//   npx tailwindcss@3 -i assets/src.css -o assets/app.css --minify
module.exports = {
  content: ["./*.php"],
  theme: { extend: {} },
};
