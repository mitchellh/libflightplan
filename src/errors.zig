/// Possible errors that can be returned by many of the functions
/// in this library. See the function doc comments for details on
/// exactly which of these can be returnd.
pub const Error = error{
    ReadFailed,
    NodeExpected,
    InvalidElement,
};
