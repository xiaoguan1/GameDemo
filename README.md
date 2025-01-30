# GameDemo
skynet引擎

后续修改目标：尽量不改动skynet引擎内部原生逻辑代码，方便后续升级引擎（升级引擎也要注意看被改动的地方）。

https://github.com/liuhaopen/SkynetMMO          git@github.com:liuhaopen/SkynetMMO.git

统一话术：
	一个节点即表示一个skynet进程

爱琳业务、引擎简述
	字符串哈希：字符串的每个字符加起来（即阿斯克码），除以某一个长度得出哈希值。

    集群：
		1：每一个节点都有固定启动的服务 和 非固定启动的服务
		例：游戏服固定启动玩家服务agent、定时器服务stimer、数据库服务databased等等
			游戏服非固定启动服务一般是某些玩法的服务，例：大型排行榜服务、某个副本的服务、战斗代理计算服务。

		2：整个集群信息表是由centerdata数据库管理，记录每一个服务器对应的全部节点信息。
		例如：节点即"ip:port" RPC的本质就是网络传输！！！ 以及其他节点信息。(centerdata 的数据格式大致为：serverId = ip:port, A服务ip:port, B服务ip:port, ...)

		案例：玩家服务需要获取A副本的一些数据信息，玩家agent服务 RPC[A服务的ip:port] 获取A服务的数据信息（这里就很有可能是跨节点通信了！）

		特别注意：centerdata库中某个serverId的节点数据信息一旦确认不可随意更改，更改要提前做好数据备份、迁移！

	战斗服务：
		

	热更新：



