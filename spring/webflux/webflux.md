```flow
st=>start: 开始
op=>operation: BaseDeviceHandler根据message判断设备消息类型
op0=>operation: 根据消息类型使用相应handler处理业务
op1=>operation: messageParse解析消息
op2=>operation: execute执行主要的业务
op3=>operation: 判断是否需要断开连接
e=>end: 结束

st->op->op0->op1->op2->op3->e
```