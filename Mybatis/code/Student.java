package com.xiaohe.mybatis.entity;

import lombok.Data;

import java.time.LocalDateTime;

/**
 * @Author smallhe
 * @Date 2022-07-01 11:41
 * @Description:
 */
@Data
public class Student {

    private Integer id;

    private String name;

    private LocalDateTime createTime;
}
