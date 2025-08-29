#ifndef PCH_H
#define PCH_H

// Windows related platforms
#if defined(_MSC_VER) || defined(WIN64) || defined(_WIN64) || defined(__WIN64__) || defined(WIN32) || defined(_WIN32) || defined(__WIN32__) || defined(__NT__)
#define EXPORT_SYMBOL __declspec(dllexport)
#define IMPORT_SYMBOL __declspec(dllimport)
#else // Other platforms (Unix related)
#define EXPORT_SYMBOL __attribute__((visibility("default")))
#define IMPORT_SYMBOL __attribute__((visibility("default")))
#endif

#endif // PCH_H
