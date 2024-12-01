import axios from 'axios';

const axiosInstanceWithBlob = axios.create({
	// Configuration
	baseURL: 'http://lb-337030458.us-east-1.elb.amazonaws.com',
	timeout: 10000,
	headers:{
		Accept:"multipart/form-data"
	}
});

// axiosInstance.interceptors.response.use(config => {
// 	if(config.status == 401)
// 	{
// 		return window.location.href = '/auth/signin'
// 	}
// 	return config;
// });

export default axiosInstanceWithBlob;