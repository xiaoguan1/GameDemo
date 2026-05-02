----- auto generate file, please do not modify -----
PROTOMAP = {
	["testresponse"] = {desc = "测试响应类型协议",
		request = "role.C2s_empty",
		response = "role.S2c_role",
		type = "response",
		id = "1",
	},
	["testpush"] = {desc = "测试推送类型协议",
		response = "role.S2c_role",
		type = "push",
		id = "2",
	},
	["testreceive"] = {desc = "测试接收类型协议",
		request = "role.C2s_empty",
		type = "notify",
		id = "3",
	},
}