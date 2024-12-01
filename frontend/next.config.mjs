/** @type {import('next').NextConfig} */
const nextConfig = {
    output: "standalone",
    images: {
        remotePatterns: [
            {
                hostname: "picsum.photos",
                protocol: "https"
            },
            {
                hostname: "d2oauojwib43g6.cloudfront.net",
                protocol: "https"
            }
        ]
    },
    redirects: () => {
        return [
            {
                source: '/',
                destination: '/auth/signin',
                permanent: true,
            }
        ]
    }
};

export default nextConfig;
