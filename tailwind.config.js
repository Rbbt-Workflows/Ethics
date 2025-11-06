module.exports = {
  content: [
    "./share/views/**/*.slim",
    "./share/views/**/*.html",
    "./share/views/public/**/*.html",
    "./share/views/public/**/*.js",
    "./lib/**/*.rb"
  ],
  theme: {
    extend: {
      colors: {
        primary: { DEFAULT: "#1d4ed8" }
      }
    }
  },
  safelist: [
    "bg-primary",
    "text-primary"
  ]
};

