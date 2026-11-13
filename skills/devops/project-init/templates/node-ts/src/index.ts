// Entry point stub so `tsc` has an input (an empty `include` fails with
// TS18003). Replace freely. Exports a function instead of logging because
// no-console is an error in this stack's lint rules.
export function main(): string {
  return 'hello'
}
