const constructListDescriptor = (desP: $FixMe, d: $FixMe) => {
  if (desP.isPointer !== true) throw Error('Pointers only')

  return desP.flatMap(
    derivedArray =>
      derivedArray && derivedArray.map(v => constructValue.default(v, d)),
  )
}

const constructValue = require('./constructValue')

export default constructListDescriptor
