exports.handler = async (event) => {
    const name = event.path ? event.path.substring(1) : "Anonymous";
    return {
        statusCode: 200,
        body: `Hello ${name}!`,
    };
};
